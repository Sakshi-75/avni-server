package org.avni.server.exporter;

import org.avni.server.domain.Individual;
import org.avni.server.service.ExportS3Service;
import org.junit.Before;
import org.junit.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;
import org.springframework.batch.core.StepContribution;
import org.springframework.batch.core.scope.context.ChunkContext;
import org.springframework.batch.core.scope.context.StepContext;
import org.springframework.batch.item.ExecutionContext;
import org.springframework.batch.repeat.RepeatStatus;

import jakarta.persistence.EntityManager;
import java.util.stream.Stream;

import static org.junit.Assert.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

public class LongitudinalExportTaskletImplTest {
    @Mock private EntityManager entityManager;
    @Mock private ExportCSVFieldExtractor exportCSVFieldExtractor;
    @Mock private ExportProcessor exportProcessor;
    @Mock private ExportS3Service exportS3Service;
    @Mock private StepContribution stepContribution;
    @Mock private ChunkContext chunkContext;
    @Mock private StepContext stepContext;
    @Mock private org.springframework.batch.core.StepExecution stepExecution;
    
    private LongitudinalExportTaskletImpl tasklet;
    
    @Before
    public void setUp() {
        MockitoAnnotations.initMocks(this);
    }
    
    @Test
    public void testExecuteWithEmptyStream() throws Exception {
        Stream<Individual> stream = Stream.empty();
        tasklet = new LongitudinalExportTaskletImpl(100, entityManager, exportCSVFieldExtractor, 
                                                     exportProcessor, exportS3Service, "job-uuid", stream);
        
        when(chunkContext.getStepContext()).thenReturn(stepContext);
        when(stepContext.getStepExecution()).thenReturn(stepExecution);
        when(stepExecution.getExecutionContext()).thenReturn(new ExecutionContext());
        when(exportS3Service.getLocalExportFile(any())).thenReturn(new java.io.File("/tmp/test.csv"));
        
        RepeatStatus status = tasklet.execute(stepContribution, chunkContext);
        
        assertEquals(RepeatStatus.FINISHED, status);
    }
    
    @Test
    public void testClean() {
        Stream<Individual> stream = Stream.empty();
        tasklet = new LongitudinalExportTaskletImpl(100, entityManager, exportCSVFieldExtractor, 
                                                     exportProcessor, exportS3Service, "job-uuid", stream);
        
        tasklet.clean();
        
        verify(entityManager, never()).flush();
    }
}
