package org.avni.server.service;

import org.avni.server.dao.OperationalProgramRepository;
import org.avni.server.dao.ProgramRepository;
import org.avni.server.dao.application.FormMappingRepository;
import org.avni.server.domain.Program;
import org.avni.server.web.request.ProgramRequest;
import org.joda.time.DateTime;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import static org.junit.Assert.*;
import static org.mockito.Mockito.*;

public class ProgramServiceTest {
    @Mock private ProgramRepository programRepository;
    @Mock private OperationalProgramRepository operationalProgramRepository;
    @Mock private FormMappingRepository formMappingRepository;
    @Mock private RuleService ruleService;
    
    private ProgramService service;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        service = new ProgramService(programRepository, operationalProgramRepository, 
                                     formMappingRepository, ruleService);
    }
    
    @Test
    public void testSaveProgramNew() {
        ProgramRequest request = new ProgramRequest();
        request.setUuid("uuid1");
        request.setName("Test Program");
        request.setActive(true);
        
        when(programRepository.findByUuid("uuid1")).thenReturn(null);
        
        service.saveProgram(request);
        
        verify(programRepository, times(2)).save(any(Program.class));
    }
    
    @Test
    public void testSaveProgramExisting() {
        ProgramRequest request = new ProgramRequest();
        request.setUuid("uuid1");
        request.setName("Updated Program");
        
        Program existing = new Program();
        existing.setUuid("uuid1");
        when(programRepository.findByUuid("uuid1")).thenReturn(existing);
        when(programRepository.save(any(Program.class))).thenReturn(existing);
        
        service.saveProgram(request);
        
        verify(programRepository, atLeast(1)).save(existing);
    }
    
    @Test
    public void testUpdateAndSaveProgram() {
        Program program = new Program();
        ProgramRequest request = new ProgramRequest();
        request.setName("New Name");
        request.setColour("Red");
        request.setActive(true);
        
        when(programRepository.save(program)).thenReturn(program);
        
        Program result = service.updateAndSaveProgram(program, request);
        
        assertEquals("New Name", result.getName());
        assertEquals("Red", result.getColour());
        verify(programRepository).save(program);
    }
}
