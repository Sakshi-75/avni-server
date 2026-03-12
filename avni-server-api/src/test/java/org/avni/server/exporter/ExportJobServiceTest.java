package org.avni.server.exporter;

import org.avni.server.dao.AvniJobRepository;
import org.avni.server.dao.ExportJobParametersRepository;
import org.avni.server.domain.Organisation;
import org.avni.server.domain.User;
import org.avni.server.domain.UserContext;
import org.avni.server.framework.security.UserContextHolder;
import org.avni.server.web.util.ErrorBodyBuilder;
import org.avni.server.web.external.request.export.ExportJobRequest;
import org.avni.server.web.external.request.export.ReportType;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.batch.core.Job;
import org.springframework.batch.core.launch.JobLauncher;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.util.ArrayList;

import static org.junit.Assert.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

public class ExportJobServiceTest {
    @Mock private AvniJobRepository avniJobRepository;
    @Mock private Job exportVisitJob;
    @Mock private Job exportV2Job;
    @Mock private JobLauncher bgJobLauncher;
    @Mock private ExportJobParametersRepository exportJobParametersRepository;
    @Mock private ErrorBodyBuilder errorBodyBuilder;
    
    private ExportJobService service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new ExportJobService(exportVisitJob, bgJobLauncher, avniJobRepository, 
                                      exportV2Job, exportJobParametersRepository, errorBodyBuilder);
    }
    
    @Test
    public void testGetAll() {
        User user = new User();
        Organisation org = new Organisation();
        UserContext context = new UserContext();
        context.setUser(user);
        context.setOrganisation(org);
        UserContextHolder.create(context);
        
        when(avniJobRepository.getJobStatuses(any(), any(), any())).thenReturn(new PageImpl<>(new ArrayList<>()));
        
        service.getAll(Pageable.unpaged());
        
        verify(avniJobRepository).getJobStatuses(any(), any(), any());
    }
    
    @Test
    public void testRunExportJobWithoutMediaDirectory() {
        User user = new User();
        user.setId(1L);
        Organisation org = new Organisation();
        org.setId(1L);
        org.setMediaDirectory(null);
        UserContext context = new UserContext();
        context.setUser(user);
        context.setOrganisation(org);
        UserContextHolder.create(context);
        
        ExportJobRequest request = new ExportJobRequest();
        request.setSubjectTypeUUID("uuid1");
        request.setReportType(ReportType.Registration);
        
        ResponseEntity<?> response = service.runExportJob(request);
        
        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.getStatusCode());
    }
}
