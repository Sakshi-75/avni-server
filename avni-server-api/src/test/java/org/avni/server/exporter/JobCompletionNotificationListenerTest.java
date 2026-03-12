package org.avni.server.exporter;

import org.avni.server.framework.security.AuthService;
import org.avni.server.service.ExportS3Service;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.batch.core.*;
import org.springframework.test.util.ReflectionTestUtils;

import java.io.File;
import java.io.IOException;
import java.util.Collections;

import static org.mockito.Mockito.*;

public class JobCompletionNotificationListenerTest {
    @Mock private ExportS3Service exportS3Service;
    @Mock private AuthService authService;
    @Mock private JobExecution jobExecution;
    @Mock private JobParameters jobParameters;
    
    private JobCompletionNotificationListener listener;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
        listener = new JobCompletionNotificationListener(exportS3Service, authService);
        ReflectionTestUtils.setField(listener, "uuid", "test-uuid");
        ReflectionTestUtils.setField(listener, "userId", 1L);
        ReflectionTestUtils.setField(listener, "organisationUUID", "org-uuid");
    }
    
    @Test
    public void testAfterJobCompleted() throws IOException {
        File mockFile = mock(File.class);
        when(jobExecution.getStatus()).thenReturn(BatchStatus.COMPLETED);
        when(jobExecution.getJobParameters()).thenReturn(jobParameters);
        when(jobParameters.getString("uuid")).thenReturn("test-uuid");
        when(exportS3Service.getLocalExportFile("test-uuid")).thenReturn(mockFile);
        
        listener.afterJob(jobExecution);
        
        verify(exportS3Service).uploadFile(mockFile, "test-uuid");
    }
    
    @Test
    public void testAfterJobFailed() {
        when(jobExecution.getStatus()).thenReturn(BatchStatus.FAILED);
        when(jobExecution.getAllFailureExceptions()).thenReturn(Collections.emptyList());
        
        listener.afterJob(jobExecution);
        
        verify(exportS3Service, never()).getLocalExportFile(any());
    }
    
    @Test
    public void testAfterJobWithUploadError() throws IOException {
        File mockFile = mock(File.class);
        when(jobExecution.getStatus()).thenReturn(BatchStatus.COMPLETED);
        when(jobExecution.getJobParameters()).thenReturn(jobParameters);
        when(jobParameters.getString("uuid")).thenReturn("test-uuid");
        when(exportS3Service.getLocalExportFile("test-uuid")).thenReturn(mockFile);
        doThrow(new IOException("Upload failed")).when(exportS3Service).uploadFile(mockFile, "test-uuid");
        
        listener.afterJob(jobExecution);
        
        verify(exportS3Service).uploadFile(mockFile, "test-uuid");
    }
    
    @Test
    public void testBeforeJob() {
        when(jobExecution.getJobParameters()).thenReturn(jobParameters);
        when(jobParameters.getString("uuid")).thenReturn("test-uuid");
        
        listener.beforeJob(jobExecution);
        
        verify(authService).authenticateByUserId(1L, "org-uuid");
    }
}
